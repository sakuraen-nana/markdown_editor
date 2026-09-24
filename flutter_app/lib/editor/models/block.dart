import 'package:flutter/foundation.dart';

/// 文档中的一个块（文档由块列表构成，见 wysiwyg design D3）。
///
/// 块类型由文本推导，不单独建模；块可含换行（多行结构块，
/// 见 file-backed-multi-doc-editing design D2/D5）。
@immutable
class MdBlock {
  const MdBlock({this.id = '', required this.text, this.recordedSeparatorAfter});

  final String id;

  /// 与下一块之间的连接符（`'\n'` 或 `'\n\n'`），仅载入自文件的块持有：
  /// 保存时原样使用，保证往返稳定；null 表示本次会话新建的边界，
  /// 保存时按结构连续规则计算（design D2/D5）。
  final String? recordedSeparatorAfter;

  final String text;

  /// 是否为 ATX 标题块（`#`–`######` + 空格开头）。
  bool get isHeading => headingPrefix.hasMatch(text);

  MdBlock copyWith({String? text, String? recordedSeparatorAfter}) => MdBlock(
    id: id,
    text: text ?? this.text,
    recordedSeparatorAfter: recordedSeparatorAfter ?? this.recordedSeparatorAfter,
  );

  static final RegExp headingPrefix = RegExp(r'^#{1,6} ');
}
