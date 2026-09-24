import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/markdown_block_controller.dart';
import '../document_codec.dart';
import '../editor_style.dart';
import '../models/block.dart';
import 'rendered_block.dart';

/// 块级双态 Markdown 编辑器（形态 B，见 design D3/D5）。
///
/// 文档 = 块列表。聚焦块为编辑态（[EditableText] + [MarkdownBlockController]，
/// 标记可见、样式实时渲染），失焦块为渲染态（[RenderedBlock]，标记隐藏）。
/// 键盘：Tab → 幽灵补全；Enter → 拆块；行首 Backspace → 合块。
class MarkdownEditor extends StatefulWidget {
  const MarkdownEditor({
    super.key,
    this.initialBlocks = const <MdBlock>[],
    this.onChanged,
  });

  /// 初始块列表；[MdBlock.recordedSeparatorAfter] 供保存回写还原原始间隔，
  /// id 由编辑器重新分配（调用方无需提供）。
  final List<MdBlock> initialBlocks;

  /// 文档发生任何变更时的回调。
  final ValueChanged<List<MdBlock>>? onChanged;

  @override
  State<MarkdownEditor> createState() => _MarkdownEditorState();
}

class _MarkdownEditorState extends State<MarkdownEditor> {
  final List<MdBlock> _blocks = [];
  final Map<String, MarkdownBlockController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  var _nextId = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialBlocks.isEmpty) {
      _createBlock(0, '', focus: false);
    } else {
      for (final block in widget.initialBlocks) {
        _createBlock(
          _blocks.length,
          block.text,
          recordedSeparator: block.recordedSeparatorAfter,
          focus: false,
        );
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_blocks.isNotEmpty) _focusNodes[_blocks.first.id]?.requestFocus();
    });
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  String _createBlock(
    int index,
    String text, {
    required bool focus,
    int cursor = 0,
    String? recordedSeparator,
  }) {
    final id = 'block-${_nextId++}';
    _blocks.insert(
      index,
      MdBlock(id: id, text: text, recordedSeparatorAfter: recordedSeparator),
    );
    final controller = MarkdownBlockController(text: text)
      ..selection = TextSelection.collapsed(offset: cursor);
    // 编辑态文本与块模型同步：否则失焦渲染与保存都会拿到旧文本。
    controller.addListener(() {
      final i = _blocks.indexWhere((block) => block.id == id);
      if (i >= 0 && _blocks[i].text != controller.text) {
        _blocks[i] = _blocks[i].copyWith(text: controller.text);
        _notifyChanged();
      }
    });
    _controllers[id] = controller;
    _focusNodes[id] = FocusNode(onKeyEvent: (_, event) => _handleKey(id, event))
      ..addListener(_rebuild);
    if (focus) _focusNodes[id]!.requestFocus();
    return id;
  }

  KeyEventResult _handleKey(String blockId, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final controller = _controllers[blockId];
    if (controller == null) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.tab) {
      if (controller.pendingCloser != null) {
        controller.commitGhost();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      final text = controller.text;
      // 多行结构块内 Enter 插入换行不拆块，保住表格/围栏/引用/列表结构
      // （spec：块编辑操作·结构块内 Enter 插入换行）。
      if (text.contains('\n') || DocumentCodec.startsWithStructure(text)) {
        _insertNewline(blockId, controller);
      } else {
        _splitBlock(blockId);
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      final selection = controller.value.selection;
      final isFirstBlock = _blocks.first.id == blockId;
      if (selection.isCollapsed && selection.baseOffset == 0 && !isFirstBlock) {
        _mergeWithPrevious(blockId);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    return KeyEventResult.ignored;
  }

  /// Enter：从光标处拆成两个块，光标落到新块行首（spec：块编辑操作）。
  void _splitBlock(String blockId) {
    final index = _blocks.indexWhere((block) => block.id == blockId);
    final controller = _controllers[blockId]!;
    final offset = controller.value.selection.baseOffset.clamp(
      0,
      controller.text.length,
    );
    final head = controller.text.substring(0, offset);
    final tail = controller.text.substring(offset);
    final original = _blocks[index];
    var newId = '';
    setState(() {
      // 拆分产生的新边界无原始间隔记录；原块与后续块的间隔归到尾块。
      _blocks[index] = MdBlock(id: blockId, text: head);
      controller.value = controller.value.copyWith(
        text: head,
        selection: const TextSelection.collapsed(offset: 0),
        composing: TextRange.empty,
      );
      newId = _createBlock(
        index + 1,
        tail,
        recordedSeparator: original.recordedSeparatorAfter,
        focus: false,
      );
    });
    // 新块的节点要等本帧 build 挂载后才能接收焦点。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[newId]?.requestFocus();
    });
    _notifyChanged();
  }

  /// 结构块内 Enter：选区替换为换行符，光标落到新行行首。
  void _insertNewline(String blockId, MarkdownBlockController controller) {
    final value = controller.value;
    final len = value.text.length;
    final base = value.selection.baseOffset.clamp(0, len);
    final extent = value.selection.extentOffset.clamp(0, len);
    final start = base <= extent ? base : extent;
    final end = base <= extent ? extent : base;
    controller.value = value.copyWith(
      text: value.text.replaceRange(start, end, '\n'),
      selection: TextSelection.collapsed(offset: start + 1),
      composing: TextRange.empty,
    );
  }

  /// 行首 Backspace：并入上一块，光标落在合并点（spec：块编辑操作）。
  void _mergeWithPrevious(String blockId) {
    final index = _blocks.indexWhere((block) => block.id == blockId);
    if (index <= 0) return;
    final previous = _blocks[index - 1];
    final current = _blocks[index];
    final controller = _controllers[previous.id]!;
    final merged = previous.text + current.text;
    final joinOffset = controller.text.length;
    setState(() {
      // 合并块接管被并块的对外间隔；两块间的间隔随合并消失。
      _blocks[index - 1] = MdBlock(
        id: previous.id,
        text: merged,
        recordedSeparatorAfter: current.recordedSeparatorAfter,
      );
      controller.value = controller.value.copyWith(
        text: merged,
        selection: TextSelection.collapsed(offset: joinOffset),
        composing: TextRange.empty,
      );
      _blocks.removeAt(index);
      _controllers.remove(current.id)?.dispose();
      _focusNodes.remove(current.id)
        ?..removeListener(_rebuild)
        ..dispose();
    });
    // 上一块的节点此刻仍在渲染态 Focus 中挂载，等本帧 build 完成再聚焦。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[previous.id]?.requestFocus();
    });
    _notifyChanged();
  }

  void _notifyChanged() {
    widget.onChanged?.call(List.unmodifiable(_blocks));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final baseStyle = EditorStyle.baseTextStyle.copyWith(
      color: colorScheme.onSurface,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final block in _blocks) _buildBlock(context, block, baseStyle),
      ],
    );
  }

  Widget _buildBlock(BuildContext context, MdBlock block, TextStyle baseStyle) {
    final node = _focusNodes[block.id]!;
    if (node.hasFocus) {
      return EditableText(
        key: ValueKey('edit-${block.id}'),
        controller: _controllers[block.id]!,
        focusNode: node,
        style: baseStyle,
        cursorColor: Theme.of(context).colorScheme.primary,
        backgroundCursorColor: Theme.of(
          context,
        ).colorScheme.onSurface.withValues(alpha: 0.3),
        keyboardType: TextInputType.multiline,
        maxLines: null,
        selectionColor: Theme.of(
          context,
        ).colorScheme.primary.withValues(alpha: 0.25),
      );
    }
    // 渲染态仍要挂载同一个 FocusNode：未 attach 的节点 requestFocus 无效，
    // 点击渲染块才能切回编辑态。
    return Focus(
      key: ValueKey('render-${block.id}'),
      focusNode: node,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: node.requestFocus,
        child: RenderedBlock(text: block.text),
      ),
    );
  }
}
