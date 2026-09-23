import 'package:flutter/material.dart';

import 'editor/widgets/markdown_editor.dart';

void main() {
  runApp(const MarkdownEditorDemoApp());
}

/// WYSIWYG 实时预览 Markdown 编辑器 demo 入口。
class MarkdownEditorDemoApp extends StatelessWidget {
  const MarkdownEditorDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Markdown 编辑器 Demo',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const DemoPage(),
    );
  }
}

class DemoPage extends StatelessWidget {
  const DemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('WYSIWYG Markdown 编辑器 Demo')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: MarkdownEditor(
              initialBlockTexts: const [
                '# WYSIWYG Markdown 编辑器',
                '聚焦的块处于编辑态：标记可见、样式实时渲染；点击其它块即切换。',
                '试试 **加粗**、*斜体*、~~删除线~~、`行内代码`、==高亮== 与公式 \\(E=mc^2\\)。输入 `**` 后按 Tab 可快速补全闭合标记。',
              ],
            ),
          ),
        ),
      ),
    );
  }
}
