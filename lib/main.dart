// Entry point — initializes Isar database and launches the app with Riverpod.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'shared/isar/isar_service.dart';
import 'features/home/domain/models/notebook.dart';
import 'features/home/domain/models/note_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Open Isar with all collection schemas before the app starts.
  await IsarService.openDatabase([
    NotebookSchema,
    NotePageSchema,
  ]);

  runApp(
    const ProviderScope(
      child: InkFlowApp(),
    ),
  );
}
