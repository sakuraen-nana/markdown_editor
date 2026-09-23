/// 测试辅助：把 InlineSpan 树压平为 (明文, 生效样式) 列表。
library;

import 'package:flutter/painting.dart';

List<(String, TextStyle)> flattenSpans(InlineSpan root) {
  final out = <(String, TextStyle)>[];
  void walk(InlineSpan span, TextStyle? parent) {
    if (span is TextSpan) {
      final effective = parent == null ? span.style : parent.merge(span.style);
      final text = span.text;
      if (text != null && text.isNotEmpty) {
        out.add((text, effective ?? const TextStyle()));
      }
      for (final child in span.children ?? const <InlineSpan>[]) {
        walk(child, effective);
      }
    }
  }

  walk(root, null);
  return out;
}

/// 按顺序拼接整棵树的明文。
String joinedText(InlineSpan root) =>
    flattenSpans(root).map((span) => span.$1).join();
