import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import 'package:markdown_editor/editor/controllers/markdown_block_controller.dart';
import 'package:markdown_editor/editor/models/block.dart';
import 'package:markdown_editor/editor/widgets/markdown_editor.dart';

import 'span_flatten.dart';

MarkdownBlockController _controllerOf(WidgetTester tester) =>
    tester.widget<EditableText>(
      find.byType(EditableText),
    ).controller as MarkdownBlockController;

String _renderedPlainText(WidgetTester tester) =>
    tester.widget<RichText>(
      find
          .descendant(of: find.byType(GptMarkdown), matching: find.byType(RichText))
          .first,
    ).text.toPlainText();

Future<void> pumpEditor(WidgetTester tester, List<String> blocks) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: Scaffold(
        body: SingleChildScrollView(
          child: MarkdownEditor(
            initialBlocks: [for (final text in blocks) MdBlock(text: text)],
          ),
        ),
      ),
    ),
  );
  // 第一帧构建 + 首块 post-frame 聚焦后的重建。
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('聚焦块为编辑态、失焦块为渲染态，点击渲染块切回编辑态', (tester) async {
    await pumpEditor(tester, ['第一段', '今天的**天气是**']);

    expect(find.byType(EditableText), findsOneWidget, reason: '仅聚焦块是编辑态');
    expect(find.byType(GptMarkdown), findsOneWidget, reason: '失焦块是渲染态');
    // 聚焦的是第一个块（编辑态）；第二个块为渲染态，标记被隐藏。
    expect(_controllerOf(tester).text, '第一段');
    expect(_renderedPlainText(tester), '今天的天气是', reason: '渲染态标记字符隐藏');

    await tester.tap(find.byType(GptMarkdown), warnIfMissed: false);
    await tester.pump();
    await tester.pump();

    // 双态互换：任意时刻只有一个编辑态块。
    expect(find.byType(EditableText), findsOneWidget);
    expect(_controllerOf(tester).text, '今天的**天气是**', reason: '被点击的块进入编辑态');
    expect(find.byType(GptMarkdown), findsOneWidget, reason: '原聚焦块转为渲染态');
  });

  testWidgets('输入 ** 出现幽灵提示，Tab 补全且光标位于两对标记之间', (tester) async {
    await pumpEditor(tester, ['']);
    await tester.enterText(find.byType(EditableText), '**');
    await tester.pump();
    await tester.pump();

    final controller = _controllerOf(tester);
    expect(controller.pendingCloser, '**');
    expect(controller.text, '**', reason: '幽灵提示不属于真实文本');

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.pump();

    expect(controller.text, '****');
    expect(controller.value.selection.baseOffset, 2);
    expect(controller.pendingCloser, isNull);
  });

  testWidgets('手动补上闭合符后提示消失且不重复', (tester) async {
    await pumpEditor(tester, ['**天气是']);
    final controller = _controllerOf(tester);
    // 初始光标在行首，先移到文本末尾让扫描覆盖整段。
    controller.selection = const TextSelection.collapsed(offset: 5);
    await tester.pump();
    expect(controller.pendingCloser, '**');

    controller.value = const TextEditingValue(
      text: '**天气是**',
      selection: TextSelection.collapsed(offset: 7),
    );
    expect(controller.pendingCloser, isNull);
    controller.commitGhost();
    expect(controller.text, '**天气是**');
  });

  testWidgets('Enter 从光标处拆块，光标落到新块行首', (tester) async {
    await pumpEditor(tester, ['AB']);
    final controller = _controllerOf(tester);
    controller.selection = const TextSelection.collapsed(offset: 1);
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump();

    expect(_controllerOf(tester).text, 'B');
    expect(_controllerOf(tester).value.selection.baseOffset, 0);
    expect(find.byType(EditableText), findsOneWidget, reason: '新块聚焦为编辑态');
    expect(_renderedPlainText(tester), 'A', reason: '原块失焦转渲染态');
  });

  testWidgets('行首 Backspace 合入上一块，光标在合并点', (tester) async {
    await pumpEditor(tester, ['A', 'B']);

    await tester.tap(find.byType(GptMarkdown));
    await tester.pump();
    await tester.pump();
    expect(_controllerOf(tester).text, 'B');

    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    await tester.pump();

    expect(find.byType(EditableText), findsOneWidget);
    expect(_controllerOf(tester).text, 'AB');
    expect(_controllerOf(tester).value.selection.baseOffset, 1);
  });

  testWidgets('标题块编辑态标记样式化、渲染态标题排版', (tester) async {
    await pumpEditor(tester, ['# 标题', '正文']);

    final context = tester.element(find.byType(EditableText));
    final controller = _controllerOf(tester);
    final spans = flattenSpans(
      controller.buildTextSpan(
        context: context,
        style: const TextStyle(fontSize: 16),
        withComposing: false,
      ),
    );
    expect(spans.any((s) => s.$1 == '# '), isTrue, reason: '编辑态标记可见');
    expect(
      spans.any((s) => s.$1 == '标题' && s.$2.fontWeight == FontWeight.w700),
      isTrue,
    );

    await tester.tap(find.byType(GptMarkdown), warnIfMissed: false);
    await tester.pump();
    await tester.pump();
    // gpt_markdown 的标题渲染带下划线占位等附加字符，用语义断言。
    final headingPlainText = _renderedPlainText(tester);
    expect(headingPlainText, contains('标题'));
    expect(headingPlainText, isNot(contains('#')), reason: '渲染态标记隐藏');
  });

  testWidgets('结构块内 Enter 插入换行不拆块（已含换行的表格块）', (tester) async {
    await pumpEditor(tester, ['| a | b |\n| --- | --- |']);
    final controller = _controllerOf(tester);
    controller.selection = const TextSelection.collapsed(offset: 9);
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump();

    expect(find.byType(EditableText), findsOneWidget, reason: '块未拆分，仍是编辑态');
    expect(_controllerOf(tester).text, '| a | b |\n\n| --- | --- |');
    expect(_controllerOf(tester).value.selection.baseOffset, 10);
    expect(find.byType(GptMarkdown), findsNothing, reason: '没有产生新块');
  });

  testWidgets('表格行单行块 Enter 续行不拆块', (tester) async {
    await pumpEditor(tester, ['| a | b |']);
    final controller = _controllerOf(tester);
    controller.selection = const TextSelection.collapsed(offset: 9);
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump();

    expect(find.byType(EditableText), findsOneWidget);
    expect(_controllerOf(tester).text, '| a | b |\n');
  });

  testWidgets('列表行块 Enter 续行不拆块，普通段落仍拆块', (tester) async {
    await pumpEditor(tester, ['- 甲']);
    final controller = _controllerOf(tester);
    controller.selection = const TextSelection.collapsed(offset: 3);
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump();
    expect(_controllerOf(tester).text, '- 甲\n', reason: '列表前缀块不拆块');

    await tester.enterText(find.byType(EditableText), '普通段落');
    await tester.pump();
    await tester.pump();
    controller.selection = const TextSelection.collapsed(offset: 2);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump();
    expect(find.byType(GptMarkdown), findsOneWidget, reason: '普通段落 Enter 拆块');
  });

  testWidgets('多行块行首 Backspace 合入上一块', (tester) async {
    await pumpEditor(tester, ['引言', '| a | b |\n| 1 | 2 |']);

    await tester.tap(find.byType(GptMarkdown), warnIfMissed: false);
    await tester.pump();
    await tester.pump();
    expect(_controllerOf(tester).text, '| a | b |\n| 1 | 2 |');

    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    await tester.pump();

    expect(find.byType(EditableText), findsOneWidget);
    expect(_controllerOf(tester).text, '引言| a | b |\n| 1 | 2 |');
    expect(_controllerOf(tester).value.selection.baseOffset, 2);
  });

  testWidgets('基准场景全流程：今天的**天气是晴天**，还不错', (tester) async {
    await pumpEditor(tester, ['']);
    final controller = _controllerOf(tester);

    // 1. 输入起始符 → 幽灵提示出现
    await tester.enterText(find.byType(EditableText), '今天的**');
    await tester.pump();
    await tester.pump();
    expect(controller.pendingCloser, '**');

    // 2. 继续输入内容 → 提示保持
    controller.value = const TextEditingValue(
      text: '今天的**天气是',
      selection: TextSelection.collapsed(offset: 8),
    );
    await tester.pump();
    expect(controller.pendingCloser, '**');

    // 3. Tab 补全 → 光标位于两对标记之间
    controller.commitGhost();
    expect(controller.text, '今天的**天气是**');
    expect(controller.value.selection.baseOffset, 8);

    // 4. 补全内容并收尾 → 闭合后样式化、无提示
    controller.value = const TextEditingValue(
      text: '今天的**天气是晴天**，还不错',
      selection: TextSelection.collapsed(offset: 15),
    );
    await tester.pump();
    await tester.pump();
    expect(controller.pendingCloser, isNull);

    final context = tester.element(find.byType(EditableText));
    final spans = flattenSpans(
      controller.buildTextSpan(
        context: context,
        style: const TextStyle(fontSize: 16),
        withComposing: false,
      ),
    );
    expect(
      spans.any((s) => s.$1 == '天气是晴天' && s.$2.fontWeight == FontWeight.w700),
      isTrue,
    );
  });
}
