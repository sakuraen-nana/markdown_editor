import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_editor/document/fixed_documents.dart';
import 'package:markdown_editor/document/template_assets.dart';
import 'package:markdown_editor/editor/document_codec.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('固定文档集', () {
    test('恰好 3 个固定文档，文件名固定', () {
      expect(kFixedDocuments, hasLength(3));
      expect(
        kFixedDocuments.map((d) => d.fileName).toSet(),
        {'welcome.md', 'notes.md', 'todo.md'},
      );
      expect(
        kFixedDocuments.map((d) => d.fileName),
        everyElement(endsWith('.md')),
        reason: '文件名均含扩展名',
      );
    });

    test('每个模板为非空有效 Markdown', () {
      for (final doc in kFixedDocuments) {
        expect(doc.template.trim(), isNotEmpty, reason: '${doc.fileName} 模板为空');
        expect(doc.displayName.trim(), isNotEmpty);
      }
    });

    test('主文档模板覆盖全部已支持特性（spec：主文档模板特性完整）', () {
      final template = kWelcomeDocument.template;
      final markers = <String, String>{
        '一级标题': '# Markdown 编辑器',
        '二级标题': '## 目录',
        '三级标题': '### 列表',
        '加粗': '**加粗**',
        '斜体': '*斜体*',
        '删除线': '~~删除线~~',
        '行内代码': '`行内代码`',
        '高亮': '==高亮==',
        '行内公式': r'\(E=mc^2\)',
        '块级公式': '\$\$',
        '表格': '| --- | --- | --- |',
        '无序列表': '- 第一项',
        '有序列表': '1. 打开文档',
        '任务勾选': '- [x] 支持实时预览',
        '引用': '> 好的编辑器',
        '代码围栏': '```dart',
        'chart 图表块': '```chart',
        '图片（本地相对路径）': '![编辑器示意图](assets/demo-image.png)',
        '目录列表': '- [快速开始](#快速开始)',
        '链接': '](https://',
        '分隔线': '\n---\n',
      };
      for (final entry in markers.entries) {
        expect(template.contains(entry.value), isTrue, reason: '缺少${entry.key}样例');
      }
    });

    test('notes/todo 模板与其定位相符', () {
      expect(kNotesDocument.template, contains('| 负责人 |'));
      expect(kTodoDocument.template, contains('- [ ] '));
    });

    test('模板可被 DocumentCodec 无损往返（与载入分块规则一致）', () {
      for (final doc in kFixedDocuments) {
        final trimmed = '${doc.template.trim()}\n';
        final blocks = DocumentCodec().decode(trimmed).blocks;
        expect(
          DocumentCodec().encode(blocks),
          trimmed,
          reason: '${doc.fileName} 模板往返后应保持不变',
        );
      }
    });
  });

  group('TemplateAssets', () {
    test('baseDirPath 为 null（内存存储/web）时跳过', () async {
      await TemplateAssets.ensureDemoImage(null);
    });

    test('缺失时从内置资产复制，已存在时不覆盖', () async {
      final temp = await Directory.systemTemp.createTemp('md_assets_test');
      addTearDown(() => temp.delete(recursive: true));

      await TemplateAssets.ensureDemoImage(temp.path);
      final target = File('${temp.path}/assets/demo-image.png');
      expect(await target.exists(), isTrue, reason: '首次调用应复制图片');
      final bytes = await target.readAsBytes();
      expect(bytes.length, greaterThan(100), reason: 'PNG 内容非空');

      final modified = await target.writeAsString('modified').then((_) async {
        await TemplateAssets.ensureDemoImage(temp.path);
        return target.readAsString();
      });
      expect(modified, 'modified', reason: '已存在时不覆盖');
    });
  });
}
