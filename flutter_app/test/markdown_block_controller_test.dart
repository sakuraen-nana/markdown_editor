import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:markdown_editor/editor/controllers/markdown_block_controller.dart';

import 'span_flatten.dart';

MarkdownBlockController _controller(String text) =>
    MarkdownBlockController(text: text);

TextSpan _buildSpan(WidgetTester tester, MarkdownBlockController controller) {
  final context = tester.element(find.byType(Scaffold));
  return controller.buildTextSpan(
    context: context,
    style: const TextStyle(fontSize: 16),
    withComposing: true,
  );
}

Future<MarkdownBlockController> _pumpHost(
  WidgetTester tester,
  String text,
) async {
  final controller = _controller(text);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const Scaffold(body: SizedBox.shrink()),
    ),
  );
  return controller;
}

void main() {
  testWidgets('已闭合加粗：内容加粗、标记弱化可见、其余文本不受影响', (tester) async {
    final controller = await _pumpHost(tester, '今天的**天气是晴天**，还不错');
    controller.selection = const TextSelection.collapsed(offset: 3);

    final spans = flattenSpans(_buildSpan(tester, controller));
    expect(joinedText(_buildSpan(tester, controller)), '今天的**天气是晴天**，还不错');
    expect(
      spans.any((s) => s.$1 == '天气是晴天' && s.$2.fontWeight == FontWeight.w700),
      isTrue,
      reason: '闭合标记的内容应以加粗显示',
    );
    expect(spans.where((s) => s.$1 == '**'), isNotEmpty, reason: '标记字符应可见');
    expect(
      spans.firstWhere((s) => s.$1 == '，还不错').$2.fontWeight,
      isNot(FontWeight.w700),
    );
  });

  testWidgets('进行中加粗即时显示，且光标后出现幽灵提示', (tester) async {
    final controller = await _pumpHost(tester, '今天的**天气是');
    controller.selection = const TextSelection.collapsed(offset: 8);

    expect(controller.pendingCloser, '**');
    final span = _buildSpan(tester, controller);
    // 幽灵提示追加在 span 树末尾，但不属于真实文本。
    expect(joinedText(span), '今天的**天气是**');
    final spans = flattenSpans(span);
    expect(
      spans.any((s) => s.$1 == '天气是' && s.$2.fontWeight == FontWeight.w700),
      isTrue,
      reason: '未闭合标记的内容也应以加粗显示',
    );
    // 幽灵 span 比标记字符更浅（ghost alpha 0.3 < dim 0.45）。
    final ghost = spans.last;
    expect(ghost.$1, '**');
    expect(ghost.$2.color!.a, closeTo(0.3, 0.01));
  });

  testWidgets('配对已闭合时不再提示幽灵（光标在闭合标记之前或之后）', (tester) async {
    final controller = await _pumpHost(tester, '**天气是**');
    controller.selection = const TextSelection.collapsed(offset: 2);
    expect(controller.pendingCloser, isNull, reason: '闭合符在光标之后已存在');
    controller.selection = const TextSelection.collapsed(offset: 7);
    expect(controller.pendingCloser, isNull, reason: '配对已完整闭合');
  });

  testWidgets('Tab 补全：闭合符写入真实文本，光标位于两对标记之间', (tester) async {
    final controller = await _pumpHost(tester, '今天的**天气是');
    controller.selection = const TextSelection.collapsed(offset: 8);

    controller.commitGhost();
    expect(controller.text, '今天的**天气是**');
    expect(controller.value.selection.baseOffset, 8);
    expect(controller.pendingCloser, isNull);
  });

  testWidgets('手动补上闭合符后提示消失，再次补全不产生重复', (tester) async {
    final controller = await _pumpHost(tester, '**天气是');
    controller.selection = const TextSelection.collapsed(offset: 5);
    expect(controller.pendingCloser, '**');

    // 模拟用户逐字输入闭合标记的最终状态。
    controller.value = const TextEditingValue(
      text: '**天气是**',
      selection: TextSelection.collapsed(offset: 7),
    );
    expect(controller.pendingCloser, isNull);
    controller.commitGhost();
    expect(controller.text, '**天气是**', reason: '无提示时补全应为空操作');
  });

  testWidgets('高亮样式：==重点== 以区别底色显示', (tester) async {
    final controller = await _pumpHost(tester, '一段==重点==文本');
    controller.selection = const TextSelection.collapsed(offset: 4);

    final context = tester.element(find.byType(Scaffold));
    final expected = Theme.of(context).colorScheme.secondaryContainer;
    final spans = flattenSpans(_buildSpan(tester, controller));
    expect(joinedText(_buildSpan(tester, controller)), '一段==重点==文本');
    expect(
      spans.any(
        (s) => s.$1 == '重点' && s.$2.backgroundColor == expected,
      ),
      isTrue,
    );
    expect(controller.pendingCloser, isNull);
  });

  testWidgets('行内公式：编辑态以区别样式显示源码，标记可见', (tester) async {
    final controller = await _pumpHost(tester, r'能量 \(E=mc^2\) 守恒');
    controller.selection = const TextSelection.collapsed(offset: 9);

    final context = tester.element(find.byType(Scaffold));
    final primary = Theme.of(context).colorScheme.primary;
    final spans = flattenSpans(_buildSpan(tester, controller));
    expect(joinedText(_buildSpan(tester, controller)), r'能量 \(E=mc^2\) 守恒');
    expect(
      spans.any((s) => s.$1 == 'E=mc^2' && s.$2.color == primary),
      isTrue,
    );
    expect(controller.pendingCloser, isNull);
  });

  testWidgets('斜体、删除线、行内代码同样实时样式化', (tester) async {
    final italic = await _pumpHost(tester, '一个*斜体*词');
    italic.selection = const TextSelection.collapsed(offset: 3);
    expect(
      flattenSpans(_buildSpan(tester, italic)).any(
        (s) => s.$1 == '斜体' && s.$2.fontStyle == FontStyle.italic,
      ),
      isTrue,
    );

    final strike = await _pumpHost(tester, '一段~~删除~~线');
    strike.selection = const TextSelection.collapsed(offset: 3);
    expect(
      flattenSpans(_buildSpan(tester, strike)).any(
        (s) =>
            s.$1 == '删除' && s.$2.decoration == TextDecoration.lineThrough,
      ),
      isTrue,
    );

    final code = await _pumpHost(tester, '一段`code`码');
    code.selection = const TextSelection.collapsed(offset: 3);
    expect(
      flattenSpans(_buildSpan(tester, code)).any(
        (s) =>
            s.$1 == 'code' && s.$2.backgroundColor != null,
      ),
      isTrue,
    );
  });

  testWidgets('中文输入法组合区间保留下划线', (tester) async {
    final controller = await _pumpHost(tester, '');
    controller.value = const TextEditingValue(
      text: '天气',
      composing: TextRange(start: 0, end: 2),
      selection: TextSelection.collapsed(offset: 2),
    );

    final spans = flattenSpans(_buildSpan(tester, controller));
    expect(
      spans.any(
        (s) => s.$1 == '天气' && s.$2.decoration == TextDecoration.underline,
      ),
      isTrue,
    );
  });

  testWidgets('标题块：# 标记弱化、正文加粗、无幽灵提示', (tester) async {
    final controller = await _pumpHost(tester, '# 标题文字');
    controller.selection = const TextSelection.collapsed(offset: 6);

    final spans = flattenSpans(_buildSpan(tester, controller));
    expect(joinedText(_buildSpan(tester, controller)), '# 标题文字');
    expect(spans.any((s) => s.$1 == '# '), isTrue);
    expect(
      spans.any((s) => s.$1 == '标题文字' && s.$2.fontWeight == FontWeight.w700),
      isTrue,
    );
    expect(controller.pendingCloser, isNull);
  });
}
