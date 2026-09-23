import 'package:flutter/material.dart';

import '../editor_style.dart';

/// 行内语法种类（demo 范围）。
enum _InlineKind { bold, italic, strike, code, highlight, latex }

/// 行内分词产物：一段文本 + 所属语法。
class _Run {
  const _Run(this.text, {this.kind, this.isMarker = false});

  final String text;
  final _InlineKind? kind;

  /// 是否为语法标记字符（`**`、`==` 等，弱化显示）。
  final bool isMarker;
}

class _ScanResult {
  const _ScanResult(this.runs, this.unclosed);

  final List<_Run> runs;

  /// 扫描结束时仍处于「进行中」（未闭合）的标记；全部闭合为 null。
  final _InlineKind? unclosed;
}

/// 单个编辑块的控制器：承担编辑态的实时渲染（design D1/D2）。
///
/// - [buildTextSpan]：每次文本变更重建样式 span——已闭合标记与进行中标记
///   都即时呈现目标样式，标记字符弱化可见；幽灵闭合符追加在 span 树末尾，
///   不进入 `value.text`。
/// - 幽灵提示是（文本, 光标）的纯函数：光标之前扫描到「进行中」标记、
///   且其闭合符不在光标之后，即提示该闭合符。无需增量状态机，
///   与行内分词共用同一套扫描逻辑，天然与样式渲染一致。
class MarkdownBlockController extends TextEditingController {
  MarkdownBlockController({required super.text});

  /// 对称标记：起始符 → 闭合符。声明顺序即分词优先级（`**` 先于 `*`）。
  static const Map<String, String> _pairs = {
    '**': '**',
    '==': '==',
    '~~': '~~',
    r'\(': r'\)',
    '`': '`',
    '*': '*',
  };

  static final RegExp _headingPrefix = RegExp(r'^#{1,6} ');

  /// 当前幽灵预填充提示；null 表示无（spec：预填充提示）。
  String? get pendingCloser => _pendingCloserOf(value.text, value.selection);

  /// Tab 补全：把提示所缺的闭合符写入真实文本，光标留在两对标记之间
  /// （spec：Tab 完成补全）。
  void commitGhost() {
    final closer = _pendingCloserOf(value.text, value.selection);
    if (closer == null) return;
    final offset = value.selection.baseOffset.clamp(0, text.length);
    value = value.copyWith(
      text: text.replaceRange(offset, offset, closer),
      selection: TextSelection.collapsed(offset: offset),
      composing: TextRange.empty,
    );
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final base = style ?? const TextStyle();
    final children = <InlineSpan>[];
    final composing = value.composing;
    if (withComposing && composing.isValid && !composing.isCollapsed) {
      // 复刻默认控制器的组合区间下划线；组合区内不分词（demo 简化）。
      final before = text.substring(0, composing.start);
      final after = text.substring(composing.end);
      if (before.isNotEmpty) children.addAll(_spansFor(context, before, base));
      children.add(
        TextSpan(
          text: text.substring(composing.start, composing.end),
          style: base.copyWith(decoration: TextDecoration.underline),
        ),
      );
      if (after.isNotEmpty) children.addAll(_spansFor(context, after, base));
    } else {
      children.addAll(_spansFor(context, text, base));
    }

    final closer = pendingCloser;
    if (closer != null) {
      final colorScheme = Theme.of(context).colorScheme;
      children.add(TextSpan(text: closer, style: EditorStyle.ghost(base, colorScheme)));
    }
    return TextSpan(style: base, children: children);
  }

  String? _pendingCloserOf(String text, TextSelection selection) {
    if (!selection.isCollapsed) return null;
    final cursor = selection.baseOffset.clamp(0, text.length);
    final head = text.substring(0, cursor);
    if (_headingPrefix.hasMatch(head)) return null;
    final unclosed = _scan(head).unclosed;
    if (unclosed == null) return null;
    final closer = _closerOf(unclosed);
    // 闭合符已存在于光标之后：配对已完整，不再提示。
    if (text.indexOf(closer, cursor) != -1) return null;
    return closer;
  }

  List<TextSpan> _spansFor(BuildContext context, String source, TextStyle base) {
    final colorScheme = Theme.of(context).colorScheme;
    final heading = _headingPrefix.firstMatch(source);
    if (heading != null) {
      // 标题块：`#` 标记弱化、正文加粗（块级样式不嵌套行内分词，demo 简化）。
      return [
        TextSpan(text: heading.group(0), style: EditorStyle.dim(base, colorScheme)),
        TextSpan(
          text: source.substring(heading.end),
          style: base.copyWith(fontWeight: FontWeight.w700),
        ),
      ];
    }
    return [
      for (final run in _scan(source).runs)
        TextSpan(text: run.text, style: _styleOf(run, base, colorScheme)),
    ];
  }

  /// 单遍扫描：非嵌套、先长后短、首个闭合符优先；未闭合标记的样式延伸至
  /// 文本末尾（design 已知限制）。转义与跨块规则不在 demo 范围。
  static _ScanResult _scan(String text) {
    final runs = <_Run>[];
    final plain = StringBuffer();
    var i = 0;

    void flush() {
      if (plain.isNotEmpty) {
        runs.add(_Run(plain.toString()));
        plain.clear();
      }
    }

    while (i < text.length) {
      String? opener;
      for (final key in _pairs.keys) {
        if (text.startsWith(key, i)) {
          opener = key;
          break;
        }
      }
      if (opener == null) {
        plain.writeCharCode(text.codeUnitAt(i));
        i++;
        continue;
      }
      final kind = _kindOf(opener);
      final closer = _pairs[opener]!;
      final contentStart = i + opener.length;
      final close = text.indexOf(closer, contentStart);
      flush();
      runs.add(_Run(opener, kind: kind, isMarker: true));
      if (close == -1) {
        // 进行中：样式延伸到扫描文本末尾。
        final rest = text.substring(contentStart);
        if (rest.isNotEmpty) runs.add(_Run(rest, kind: kind));
        return _ScanResult(runs, kind);
      }
      final content = text.substring(contentStart, close);
      if (content.isNotEmpty) runs.add(_Run(content, kind: kind));
      runs.add(_Run(closer, kind: kind, isMarker: true));
      i = close + closer.length;
    }
    flush();
    return _ScanResult(runs, null);
  }

  static _InlineKind _kindOf(String opener) => switch (opener) {
    '**' => _InlineKind.bold,
    '==' => _InlineKind.highlight,
    '~~' => _InlineKind.strike,
    r'\(' => _InlineKind.latex,
    '`' => _InlineKind.code,
    '*' => _InlineKind.italic,
    _ => throw ArgumentError.value(opener, 'opener', '未知起始符'),
  };

  static String _closerOf(_InlineKind kind) => switch (kind) {
    _InlineKind.bold => '**',
    _InlineKind.italic => '*',
    _InlineKind.strike => '~~',
    _InlineKind.code => '`',
    _InlineKind.highlight => '==',
    _InlineKind.latex => r'\)',
  };

  TextStyle _styleOf(_Run run, TextStyle base, ColorScheme colorScheme) {
    final kind = run.kind;
    if (kind == null) return base;
    final content = switch (kind) {
      _InlineKind.bold => EditorStyle.bold(base),
      _InlineKind.italic => EditorStyle.italic(base),
      _InlineKind.strike => EditorStyle.strike(base),
      _InlineKind.code => EditorStyle.inlineCode(base, colorScheme),
      _InlineKind.highlight => EditorStyle.highlight(base, colorScheme),
      _InlineKind.latex => EditorStyle.latex(base, colorScheme),
    };
    return run.isMarker ? EditorStyle.dim(content, colorScheme) : content;
  }
}
