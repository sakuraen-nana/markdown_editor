import 'package:flutter/foundation.dart';

/// 文档中的一个块（形态 B：文档由块列表构成，见 design D3）。
///
/// 块类型由文本推导，不单独建模；demo 范围内只有段落与标题两类。
@immutable
class MdBlock {
  const MdBlock({required this.id, required this.text});

  final String id;
  final String text;

  /// 是否为 ATX 标题块（`#`–`######` + 空格开头）。
  bool get isHeading => headingPrefix.hasMatch(text);

  MdBlock copyWith({String? text}) => MdBlock(id: id, text: text ?? this.text);

  static final RegExp headingPrefix = RegExp(r'^#{1,6} ');
}
