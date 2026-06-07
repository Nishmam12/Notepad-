## Isar Models
- `lib/features/home/domain/models/notebook.dart` · `Notebook`
  - `Id id`
  - `String title`
  - `DateTime createdAt`
  - `DateTime modifiedAt`
  - `int pageCount`
- `lib/features/home/domain/models/note_page.dart` · `NotePage`
  - `Id id`
  - `int notebookId`
  - `int pageIndex`
  - `DateTime createdAt`

## .ink Storage Path
`{getApplicationDocumentsDirectory()}/notes/{notebookId}/{pageId}.ink`

## Routing Structure
- `/` -> `HomeScreen`
- `/note/:id` -> `NoteEditorScreen`

## Riverpod Providers
- `noteRepositoryProvider` · `Provider<NoteRepository>` · `lib/features/home/presentation/home_notifier.dart`
- `homeNotifierProvider` · `StateNotifierProvider<HomeNotifier, List<Notebook>>` · `lib/features/home/presentation/home_notifier.dart`
- `canvasStateProvider` · `StateNotifierProvider.autoDispose<CanvasStateNotifier, CanvasState>` · `lib/features/editor/presentation/canvas_notifier.dart`
- `toolProvider` · `StateNotifierProvider<ToolNotifier, ToolState>` · `lib/features/editor/presentation/canvas_notifier.dart`
- `undoRedoProvider` · `StateNotifierProvider.autoDispose<UndoRedoNotifier, UndoRedoState>` · `lib/features/editor/domain/undo_redo/undo_redo_stack.dart`

## Schema Changes Required
- `NotePage` model needs `modifiedAt` (`DateTime`).
  - *Reason:* Phase 3 requires tracking page modification.
  - *Note:* The prompt references a new `PageModel` with `String notebookId`. However, per the rule "NEVER remove or rename existing fields", we will retain the existing `NotePage` name and `int notebookId` (since `Notebook.id` is an `int`). We will adapt the signature of `PageRepository` to match `int notebookId`.

## Migration Risks
- **Path format mismatch:** `InkFileStorage` currently stores files as `{pageId}.ink` (using the Isar ID). Phase 3 requires `{getApplicationDocumentsDirectory()}/notes/{notebookId}/page_{pageIndex}.ink`. Existing files created in Phase 1/2 will not be found under the new format unless migrated.
- **Index tracking:** Existing `NotePage` records may not have correctly managed `pageIndex` contiguity during Phase 1/2.
- **Type mismatch:** The Phase 3 prompt specifies `String notebookId` for the repository, but Isar `Id` in `Notebook` is currently an `int` (auto-incremented). The repository must adapt to use `int notebookId`.

## Baseline flutter analyze
```
Analyzing Inkflow...                                            
No issues found! (ran in 38.8s)
```
