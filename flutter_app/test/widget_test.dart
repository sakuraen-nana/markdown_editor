import 'package:flutter_test/flutter_test.dart';

import 'package:markdown_editor/editor/widgets/markdown_editor.dart';
import 'package:markdown_editor/main.dart';

void main() {
  testWidgets('demo 应用启动并显示编辑器', (tester) async {
    await tester.pumpWidget(const MarkdownEditorDemoApp());
    await tester.pump();
    await tester.pump();

    expect(find.text('WYSIWYG Markdown 编辑器 Demo'), findsOneWidget);
    expect(find.byType(MarkdownEditor), findsOneWidget);
  });
}
