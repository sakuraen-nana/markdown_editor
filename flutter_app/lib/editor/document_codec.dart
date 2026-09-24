import 'models/block.dart';

/// 载入结果：块列表 + 文件尾换行记录（保存时还原，design D3/D4）。
class DecodedDocument {
  const DecodedDocument({required this.blocks, required this.trailingNewline});

  final List<MdBlock> blocks;
  final bool trailingNewline;
}

/// 文件内容 ↔ 块列表的双向映射（spec：文件载入分块、保存回写）。
///
/// 载入：以空行为分块边界，代码围栏内的空行不作为边界（整个围栏归为
/// 一个块）；相邻块的原始间隔记录在 [MdBlock.recordedSeparatorAfter]。
/// 保存：recorded 间隔原样使用保证往返稳定；本次会话新建的边界按结构
/// 连续规则计算——同为表格行、引用行或同种列表项时以单换行连接。
class DocumentCodec {
  const DocumentCodec();

  /// CRLF 统一按 LF 处理（往返稳定按行内容定义，见 design 风险项）。
  DecodedDocument decode(String source) {
    final normalized = source.replaceAll('\r\n', '\n');
    final trailingNewline = normalized.endsWith('\n');
    final lines = normalized.split('\n');
    if (trailingNewline) lines.removeLast();

    final blocks = <MdBlock>[];
    var current = <String>[];
    var inFence = false;
    var fenceMarker = '';

    void flush() {
      if (current.isEmpty) return;
      blocks.add(
        MdBlock(
          text: current.join('\n'),
          // 文件级分块边界都是空行连接；末块的 recorded 无意义，仍记录
          // '\n\n'，encode 时最后一个块不会使用它。
          recordedSeparatorAfter: '\n\n',
        ),
      );
      current = <String>[];
    }

    for (final line in lines) {
      final trimmed = line.trim();
      if (inFence) {
        current.add(line);
        if (trimmed.startsWith(fenceMarker)) {
          inFence = false;
          fenceMarker = '';
        }
        continue;
      }
      if (trimmed.isEmpty) {
        flush();
        continue;
      }
      if (trimmed.startsWith('```') || trimmed.startsWith('~~~')) {
        inFence = true;
        fenceMarker = trimmed.startsWith('```') ? '```' : '~~~';
      }
      current.add(line);
    }
    flush();

    if (blocks.isEmpty) blocks.add(const MdBlock(text: ''));
    return DecodedDocument(blocks: blocks, trailingNewline: trailingNewline);
  }

  String encode(List<MdBlock> blocks, {bool trailingNewline = true}) {
    final buffer = StringBuffer();
    for (var i = 0; i < blocks.length; i++) {
      buffer.write(blocks[i].text);
      if (i == blocks.length - 1) break;
      buffer.write(_separatorBetween(blocks[i], blocks[i + 1]));
    }
    if (trailingNewline && buffer.isNotEmpty) buffer.write('\n');
    return buffer.toString();
  }

  /// 块间连接符：recorded 优先（往返稳定）；新建边界按结构连续规则。
  String _separatorBetween(MdBlock block, MdBlock next) {
    final recorded = block.recordedSeparatorAfter;
    if (recorded != null) return recorded;
    return _isSameStructure(block.text, next.text) ? '\n' : '\n\n';
  }

  /// 相邻两块是否应写回为连续结构（design D5）。
  static bool _isSameStructure(String a, String b) {
    final firstA = a.split('\n').first.trim();
    final firstB = b.split('\n').first.trim();
    return _isTableRow(firstA) && _isTableRow(firstB) ||
        _isQuoteLine(firstA) && _isQuoteLine(firstB) ||
        _sameListMarker(firstA, firstB);
  }

  static bool _isTableRow(String line) => line.startsWith('|');

  static bool _isQuoteLine(String line) => line.startsWith('>');

  static final RegExp _unordered = RegExp(r'^([-*+]) ');
  static final RegExp _ordered = RegExp(r'^\d+[.)] ');

  /// 无序列表要求同一 bullet 字符（`-` 与 `*` 相邻是两个列表，
  /// CommonMark）；有序列表只要求均为有序项。
  static bool _sameListMarker(String a, String b) {
    final ua = _unordered.firstMatch(a);
    final ub = _unordered.firstMatch(b);
    if (ua != null || ub != null) {
      return ua != null && ub != null && ua.group(1) == ub.group(1);
    }
    return _ordered.hasMatch(a) && _ordered.hasMatch(b);
  }

  /// 块首行是否命中结构前缀（表格行/引用/围栏/列表标记）——
  /// Enter 不拆块的判定依据之一（design D5）。
  static bool startsWithStructure(String text) {
    final line = text.split('\n').first.trimLeft();
    return _isTableRow(line) ||
        _isQuoteLine(line) ||
        line.startsWith('```') ||
        line.startsWith('~~~') ||
        _unordered.hasMatch(line) ||
        _ordered.hasMatch(line);
  }
}
