import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_editor/document/document_store.dart';
import 'package:markdown_editor/editor/widgets/markdown_editor.dart';
import 'package:markdown_editor/main.dart';

/// 等待异步初始化完成（内存存储为纯微任务，几帧即就绪）。
Future<void> pumpReady(WidgetTester tester, {DocumentStore? store}) async {
  await tester.pumpWidget(
    MaterialApp(home: WorkspacePage(store: store ?? MemoryDocumentStore())),
  );
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

Future<void> openDrawer(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.menu));
  await tester.pumpAndSettle();
}

Future<void> tapDocument(WidgetTester tester, String fileName) async {
  await tester.tap(find.byKey(ValueKey('doc-item-$fileName')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('首次启动自动创建固定文档并默认打开主文档', (tester) async {
    final store = MemoryDocumentStore();
    await pumpReady(tester, store: store);

    expect(find.text('欢迎与功能总览'), findsOneWidget, reason: '标题栏为当前文档');
    expect(find.byType(MarkdownEditor), findsOneWidget);
    expect(find.textContaining('欢迎使用实时预览编辑器'), findsOneWidget);
    for (final fileName in ['welcome.md', 'notes.md', 'todo.md']) {
      expect(await store.read(fileName), isNotNull, reason: '$fileName 已创建');
    }
  });

  testWidgets('抽屉列出固定文档并高亮当前文档，无修改切换不弹窗', (tester) async {
    await pumpReady(tester);
    await openDrawer(tester);

    expect(find.text('欢迎与功能总览'), findsNWidgets(2), reason: '标题栏 + 抽屉项');
    expect(find.text('笔记'), findsOneWidget);
    expect(find.text('待办'), findsOneWidget);
    expect(find.byIcon(Icons.fiber_manual_record), findsNothing, reason: '无脏标记');

    await tapDocument(tester, 'notes.md');

    expect(find.text('当前文档有未保存修改'), findsNothing, reason: '无修改直接切换');
    expect(find.text('笔记'), findsOneWidget, reason: '标题栏切换为笔记');
    expect(find.textContaining('块级双态'), findsOneWidget, reason: '笔记内容载入');
  });

  testWidgets('切换时出现脏标记，选择「保存并切换」写盘并切换', (tester) async {
    final store = MemoryDocumentStore();
    await pumpReady(tester, store: store);

    await tester.enterText(find.byType(EditableText), 'X');
    await tester.pump();
    await tester.pump();
    expect(find.text('欢迎与功能总览 •'), findsOneWidget, reason: '修改后标题栏出现脏标记');

    await openDrawer(tester);
    expect(find.byIcon(Icons.fiber_manual_record), findsOneWidget, reason: '抽屉项脏标记');

    await tapDocument(tester, 'todo.md');
    expect(find.text('当前文档有未保存修改'), findsOneWidget, reason: '弹出确认对话框');

    await tester.tap(find.text('保存并切换'));
    await tester.pumpAndSettle();

    expect(find.text('待办'), findsOneWidget, reason: '已切换到待办');
    // enterText 只改第一个块，其余块保持原样。
    expect(
      await store.read('welcome.md'),
      startsWith('X\n\n欢迎使用实时预览编辑器'),
      reason: '原文档已写盘',
    );
  });

  testWidgets('选择「放弃修改并切换」不写盘', (tester) async {
    final store = MemoryDocumentStore();
    await pumpReady(tester, store: store);

    await tester.enterText(find.byType(EditableText), 'X');
    await tester.pump();
    await tester.pump();

    await openDrawer(tester);
    await tapDocument(tester, 'notes.md');
    await tester.tap(find.text('放弃修改并切换'));
    await tester.pumpAndSettle();

    expect(find.text('笔记'), findsOneWidget);
    final content = await store.read('welcome.md');
    expect(content, isNot(contains('X')), reason: '未写盘');
    expect(content, contains('# Markdown 编辑器'), reason: '保持已保存内容');
  });

  testWidgets('选择「取消」留在当前文档且修改保留', (tester) async {
    await pumpReady(tester);

    await tester.enterText(find.byType(EditableText), 'X');
    await tester.pump();
    await tester.pump();

    await openDrawer(tester);
    await tapDocument(tester, 'todo.md');
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(find.text('欢迎与功能总览 •'), findsOneWidget, reason: '仍为原文档且未保存');
    // 打开抽屉时编辑块失焦转为渲染态，修改以渲染文本呈现。
    expect(find.text('X'), findsOneWidget, reason: '修改保留');
  });

  testWidgets('Ctrl+S 保存写盘、清除脏标记并提示', (tester) async {
    final store = MemoryDocumentStore();
    await pumpReady(tester, store: store);

    await tester.enterText(find.byType(EditableText), 'X');
    await tester.pump();
    await tester.pump();
    expect(find.text('欢迎与功能总览 •'), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('已保存'), findsOneWidget, reason: 'SnackBar 反馈');
    expect(find.text('欢迎与功能总览'), findsOneWidget, reason: '脏标记消除');
    expect(
      await store.read('welcome.md'),
      startsWith('X\n\n欢迎使用实时预览编辑器'),
      reason: '内容已写盘',
    );
  });

  testWidgets('保存按钮仅在脏状态下可用', (tester) async {
    await pumpReady(tester);

    final iconButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.save_outlined),
    );
    expect(iconButton.onPressed, isNull, reason: '未修改时保存按钮禁用');
  });
}
