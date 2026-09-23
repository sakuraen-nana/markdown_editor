import 'package:flutter/material.dart';

/// 编辑态与渲染态共用的样式 token（design D4：降低双管线视觉偏差）。
class EditorStyle {
  const EditorStyle._();

  /// 正文基础样式，编辑态与渲染态共用。
  static const TextStyle baseTextStyle = TextStyle(fontSize: 16, height: 1.6);

  static TextStyle bold(TextStyle base) =>
      base.copyWith(fontWeight: FontWeight.w700);

  static TextStyle italic(TextStyle base) =>
      base.copyWith(fontStyle: FontStyle.italic);

  static TextStyle strike(TextStyle base) =>
      base.copyWith(decoration: TextDecoration.lineThrough);

  static TextStyle inlineCode(TextStyle base, ColorScheme colorScheme) =>
      base.copyWith(
        fontFamily: 'monospace',
        backgroundColor: colorScheme.onSurface.withValues(alpha: 0.08),
      );

  /// `==…==` 高亮：区别于正文底色。
  static TextStyle highlight(TextStyle base, ColorScheme colorScheme) =>
      base.copyWith(backgroundColor: colorScheme.secondaryContainer);

  /// 行内公式的编辑态源码样式。
  static TextStyle latex(TextStyle base, ColorScheme colorScheme) =>
      base.copyWith(color: colorScheme.primary);

  /// 语法标记字符的弱化处理：可见但退居背景（Typora 式观感）。
  static TextStyle dim(TextStyle style, ColorScheme colorScheme) =>
      style.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.45));

  /// 幽灵预填充提示：比标记更虚更浅（spec：预填充提示）。
  static TextStyle ghost(TextStyle style, ColorScheme colorScheme) =>
      style.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.3));
}
