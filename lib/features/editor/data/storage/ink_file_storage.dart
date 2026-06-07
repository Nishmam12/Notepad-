// Save and load strokes to/from .ink JSON files in the app documents directory.

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../domain/models/stroke.dart';

class InkFileStorage {
  /// Returns the directory path for a notebook's ink files.
  static Future<String> _notebookDir(int notebookId) async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = '${appDir.path}/notes/$notebookId';
    await Directory(dir).create(recursive: true);
    return dir;
  }

  /// Returns the file path for a specific page's ink data.
  static Future<String> _pageFilePath(int notebookId, int pageId) async {
    final dir = await _notebookDir(notebookId);
    return '$dir/$pageId.ink';
  }

  /// Saves a list of strokes to an .ink file for a given notebook and page.
  static Future<void> saveStrokes({
    required int notebookId,
    required int pageId,
    required List<Stroke> strokes,
  }) async {
    final filePath = await _pageFilePath(notebookId, pageId);
    final file = File(filePath);

    final data = strokes.map((s) => s.toMap()).toList();
    final jsonString = jsonEncode(data);
    await file.writeAsString(jsonString);
  }

  /// Loads strokes from an .ink file for a given notebook and page.
  /// Returns an empty list if the file does not exist.
  static Future<List<Stroke>> loadStrokes({
    required int notebookId,
    required int pageId,
  }) async {
    final filePath = await _pageFilePath(notebookId, pageId);
    final file = File(filePath);

    if (!await file.exists()) {
      return [];
    }

    final jsonString = await file.readAsString();
    final data = jsonDecode(jsonString) as List<dynamic>;
    return data
        .map((item) => Stroke.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  /// Deletes all ink files for a given notebook.
  static Future<void> deleteNotebookInkFiles(int notebookId) async {
    final dir = await _notebookDir(notebookId);
    final directory = Directory(dir);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  /// Deletes the ink file for a specific page.
  static Future<void> deletePageInkFile({
    required int notebookId,
    required int pageId,
  }) async {
    final filePath = await _pageFilePath(notebookId, pageId);
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
