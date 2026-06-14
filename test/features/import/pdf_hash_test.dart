import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/import/pdf_service.dart';

void main() {
  // Regression for BUG-11: the PDF page cache key must be deterministic
  // (stable across runs) and content-based so distinct PDFs never collide.
  group('pdfContentHashHex', () {
    test('is deterministic for identical bytes', () {
      final bytes = List<int>.generate(256, (i) => i % 251);
      expect(pdfContentHashHex(bytes), pdfContentHashHex(bytes));
    });

    test('differs for different content', () {
      final a = [1, 2, 3, 4, 5];
      final b = [1, 2, 3, 4, 6];
      expect(pdfContentHashHex(a), isNot(pdfContentHashHex(b)));
    });

    test('produces a clean, fixed-width positive hex string', () {
      final hash = pdfContentHashHex([10, 20, 30]);
      expect(hash.length, 15);
      expect(hash.contains('-'), isFalse);
      expect(RegExp(r'^[0-9a-f]+$').hasMatch(hash), isTrue);
    });
  });
}
