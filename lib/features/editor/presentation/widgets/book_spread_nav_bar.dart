import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../book_view_notifier.dart';
import '../page_notifier.dart';

class BookSpreadNavBar extends ConsumerWidget {
  final int notebookId;
  
  const BookSpreadNavBar({super.key, required this.notebookId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookViewState = ref.watch(bookViewProvider(notebookId));
    final pageState = ref.watch(pageProvider(notebookId));
    final totalPages = pageState.pages.length;
    final maxSpread = totalPages ~/ 2;
    
    return Container(
      height: 60,
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios, 
                color: bookViewState.currentSpread > 0 ? AppColors.textPrimary : AppColors.textMuted),
            onPressed: bookViewState.currentSpread > 0 
                ? () => ref.read(bookViewProvider(notebookId).notifier).previousSpread()
                : null,
          ),
          Text(
            'Spread ${bookViewState.currentSpread} / $maxSpread',
            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500),
          ),
          IconButton(
            icon: Icon(Icons.arrow_forward_ios, 
                color: bookViewState.currentSpread < maxSpread ? AppColors.textPrimary : AppColors.textMuted),
            onPressed: bookViewState.currentSpread < maxSpread
                ? () => ref.read(bookViewProvider(notebookId).notifier).nextSpread()
                : null,
          ),
        ],
      ),
    );
  }
}

