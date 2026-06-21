import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/editor/render/dash_path.dart';

void main() {
  test('dashed breaks a line into multiple shorter segments', () {
    final src = Path()
      ..moveTo(0, 0)
      ..lineTo(100, 0);
    final dashed = DashPath.dashed(src, dash: 10, gap: 10);

    final metrics = dashed.computeMetrics().toList();
    expect(metrics.length, greaterThan(1));

    final total = metrics.fold<double>(0, (sum, m) => sum + m.length);
    expect(total, lessThan(100)); // gaps removed total ink length
  });
}
