// GoRouter configuration — defines all app routes.

import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/home/presentation/screens/home_screen.dart';
import '../features/editor/presentation/screens/note_editor_screen.dart';
import '../features/editor/presentation/screens/book_view_screen.dart';
import '../features/import/presentation/pdf_import_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';
import '../features/settings/presentation/screens/about_screen.dart';

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
        // Guard against missing/malformed `extra` (e.g. deep links) instead of
        // casting blindly, which would throw and crash navigation.
        final extra = state.extra;
        if (extra is Map &&
            extra['notebookId'] is int &&
            extra['pageIndex'] is int) {
          return PdfImportScreen(
            notebookId: extra['notebookId'] as int,
            initialPageIndex: extra['pageIndex'] as int,
          );
        }
        return const HomeScreen();
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
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/about',
      builder: (context, state) => const AboutScreen(),
    ),
  ],
);

final routerProvider = Provider<GoRouter>((ref) => appRouter);
