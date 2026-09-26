import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import '../editor_style.dart';
import 'chart_block_view.dart';

/// 渲染态块：光标离开后以 gpt_markdown 渲染（wysiwyg design D4）。
///
/// 仅使用 gpt_markdown 现行 API（`GptMarkdown`、`InlinePattern`、
/// `blockComponents`、`imageBuilder`），不触碰任何 `@Deprecated` 成员——
/// 见 AGENTS.md「依赖约束」。点击切换编辑态由外层 [MarkdownEditor] 负责。
class RenderedBlock extends StatelessWidget {
  const RenderedBlock({super.key, required this.text});

  final String text;

  /// `==…==` 高亮扩展：gpt_markdown 内置不含此扩展语法，经现行
  /// [InlinePattern] 注入（其模式先于内置组件匹配，见 wysiwyg design D4）。
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

  /// chart 围栏块扩展（file-backed design D6）；顶层 final 实例保持稳定。
  static final List<MarkdownBlockComponent> blockComponents = [
    kChartBlockComponent,
  ];

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
      blockComponents: blockComponents,
      imageBuilder: (context, url, width, height) =>
          MarkdownImage.build(context, url, width, height),
    );
  }
}

/// 图片渲染分流（file-backed design D7）：网络地址走 `Image.network`；
/// 本地地址按字面或相对数据目录解析，缺失显示错误占位（spec：本地图片
/// 渲染）。
class MarkdownImage {
  MarkdownImage._();

  /// 本地相对路径的解析基准目录（数据目录）；null 时相对路径一律视为
  /// 缺失。由应用启动时设置（workspace）。
  static String? basePath;

  static Widget build(
    BuildContext context,
    String url,
    double? width,
    double? height,
  ) {
    final image =
        url.startsWith('http://') || url.startsWith('https://')
            ? Image.network(
                url,
                width: width,
                height: height,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => _placeholder(context, url),
              )
            : _localImage(context, url, width, height);
    return image;
  }

  static Widget _localImage(
    BuildContext context,
    String url,
    double? width,
    double? height,
  ) {
    final path = resolvePath(url);
    final File? file = path == null ? null : File(path);
    if (file == null || !file.existsSync()) {
      return _placeholder(context, url);
    }
    return Image.file(
      file,
      width: width,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => _placeholder(context, url),
    );
  }

  /// `file://` 与绝对路径按字面；其余相对 [basePath]（数据目录）。
  static String? resolvePath(String url) {
    var path = url;
    if (path.startsWith('file://')) {
      path = path.substring('file://'.length);
    }
    if (path.startsWith('/') || path.startsWith(RegExp(r'^[A-Za-z]:[\\/]'))) {
      return path;
    }
    final base = basePath;
    if (base == null) return null;
    if (base.endsWith('/')) return '$base$path';
    return '$base/$path';
  }

  static Widget _placeholder(BuildContext context, String url) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined, color: colorScheme.outline),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '图片缺失：$url',
              style: TextStyle(color: colorScheme.outline, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
