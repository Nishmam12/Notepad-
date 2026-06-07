// GoRouter configuration — defines all app routes.

import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/home/presentation/screens/home_screen.dart';
import '../features/editor/presentation/screens/note_editor_screen.dart';
import '../features/editor/presentation/screens/book_view_screen.dart';
import '../features/import/presentation/pdf_import_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/import/pdf',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return PdfImportScreen(
          notebookId: extra['notebookId'] as int,
          initialPageIndex: extra['pageIndex'] as int,
        );
      },
    ),
    GoRoute(
      path: '/note/:id',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return NoteEditorScreen(notebookId: id);
      },
      routes: [
        GoRoute(
          path: 'book',
          builder: (context, state) {
            final id = int.parse(state.pathParameters['id']!);
            return BookViewScreen(notebookId: id);
          },
        ),
      ],
    ),
  ],
);

final routerProvider = Provider<GoRouter>((ref) => appRouter);
