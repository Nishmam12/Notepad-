// Centralized storage path definitions
class StoragePaths {
  /// Base directory for a specific notebook.
  static String getNotebookDir(String docsDir, String notebookId) =>
      '$docsDir/notes/$notebookId';

  /// Path for the binary .ink file containing strokes for a specific page.
  static String getInkFilePath(String docsDir, String notebookId, int pageIndex) =>
      '${getNotebookDir(docsDir, notebookId)}/page_$pageIndex.ink';

  /// Path for the thumbnail image of a specific page.
  static String getThumbnailPath(String docsDir, String notebookId, int pageIndex) =>
      '${getNotebookDir(docsDir, notebookId)}/thumb_$pageIndex.png';

  /// Relative path for cached PDF pages (relative to docsDir).
  static String getPdfPageCacheRelativePath(String notebookId, String pdfHash, int pageIndex) =>
      'notes/$notebookId/imports/pdf_${pdfHash}_$pageIndex.png';

  /// Relative path for cached free images (relative to docsDir).
  static String getFreeImageCacheRelativePath(String notebookId, String contentId) =>
      'notes/$notebookId/imports/img_$contentId.png';
}
