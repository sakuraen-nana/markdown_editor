import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import '../editor_style.dart';

/// 渲染态块：光标离开后以 gpt_markdown 渲染（design D4）。
///
/// 仅使用 gpt_markdown 现行 API（`GptMarkdown`、`InlinePattern`、`style`），
/// 不触碰任何 `@Deprecated` 成员——见 CLAUDE.md「依赖约束」。
/// 点击切换编辑态由外层 [MarkdownEditor] 的 GestureDetector 负责。
class RenderedBlock extends StatelessWidget {
  const RenderedBlock({super.key, required this.text});

  final String text;

  /// `==…==` 高亮扩展：gpt_markdown 内置不含此扩展语法，经现行
  /// [InlinePattern] 注入（其模式先于内置组件匹配，见 design D4）。
  List<InlinePattern> _highlightPatterns(ColorScheme colorScheme) {
    return [
      InlinePattern(
        pattern: RegExp(r'==([^=\n]+)=='),
        builder: (context, match, style) => TextSpan(
          text: match.group(1),
          style: EditorStyle.highlight(style, colorScheme),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (text.trim().isEmpty) {
      // 空块保持最小高度，避免布局塌陷。
      return SizedBox(height: EditorStyle.baseTextStyle.fontSize! * 1.6);
    }
    return GptMarkdown(
      text,
      style: EditorStyle.baseTextStyle.copyWith(color: colorScheme.onSurface),
      inlinePatterns: _highlightPatterns(colorScheme),
    );
  }
}
