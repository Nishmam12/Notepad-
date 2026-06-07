// StateNotifier that manages the list of notebooks via NoteRepository.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/note_repository.dart';
import '../domain/models/notebook.dart';
import '../../../shared/isar/isar_service.dart';

class HomeNotifier extends StateNotifier<List<Notebook>> {
  final NoteRepository _repository;

  HomeNotifier(this._repository) : super([]);

  /// Loads all notebooks from the database into state.
  Future<void> loadNotebooks() async {
    state = await _repository.getAllNotebooks();
  }

  /// Creates a new notebook and refreshes the list.
  Future<Notebook> createNotebook(String title) async {
    final notebook = await _repository.createNotebook(title);
    await loadNotebooks();
    return notebook;
  }

  /// Deletes a notebook by ID and refreshes the list.
  Future<void> deleteNotebook(int id) async {
    await _repository.deleteNotebook(id);
    await loadNotebooks();
  }

  /// Updates an existing notebook and refreshes the list.
  Future<void> updateNotebook(Notebook notebook) async {
    await _repository.updateNotebook(notebook);
    await loadNotebooks();
  }
}

/// Provider for the NoteRepository, depends on the Isar instance.
final noteRepositoryProvider = Provider<NoteRepository>((ref) {
  return NoteRepository(IsarService.instance);
});

/// Provider for the HomeNotifier, auto-loads notebooks on creation.
final homeNotifierProvider =
    StateNotifierProvider<HomeNotifier, List<Notebook>>((ref) {
  final repository = ref.watch(noteRepositoryProvider);
  final notifier = HomeNotifier(repository);
  notifier.loadNotebooks();
  return notifier;
});
