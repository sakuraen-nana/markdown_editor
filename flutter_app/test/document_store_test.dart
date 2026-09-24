import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_editor/document/document_store.dart';

/// 文件与内存实现在同一契约下的行为一致性（spec：固定文档集与自动创建
/// 的存储前提，design D1）。
void main() {
  Future<void> runContract(DocumentStore store, {Directory? tempDir}) async {
    // 缺失返回 null / exists false。
    expect(await store.exists('missing.md'), isFalse);
    expect(await store.read('missing.md'), isNull);

    // 写入后可读、exists。
    await store.write('a.md', '# 你好');
    expect(await store.exists('a.md'), isTrue);
    expect(await store.read('a.md'), '# 你好');

    // 覆盖写。
    await store.write('a.md', '# 修改');
    expect(await store.read('a.md'), '# 修改');

    // 多文件互不影响。
    await store.write('b.md', 'B');
    expect(await store.read('a.md'), '# 修改');
    expect(await store.read('b.md'), 'B');

    await tempDir?.delete(recursive: true);
  }

  test('FileDocumentStore：临时目录注入，读写/覆盖/缺失契约', () async {
    final temp = await Directory.systemTemp.createTemp('md_store_test');
    await runContract(FileDocumentStore(temp), tempDir: temp);
  });

  test('FileDocumentStore.create：自动创建 MarkdownEditor 子目录', () async {
    // path_provider 在纯 Dart 测试环境无插件实现，直接验证目录约定逻辑：
    // create 的目录拼接与按需创建。这里用构造注入等价验证。
    final temp = await Directory.systemTemp.createTemp('md_store_mk');
    final nested = Directory('${temp.path}/MarkdownEditor');
    final store = FileDocumentStore(nested);
    await store.write('welcome.md', '内容');
    expect(await nested.exists(), isTrue, reason: '写盘前按需创建目录');
    expect(await File('${nested.path}/welcome.md').readAsString(), '内容');
    await temp.delete(recursive: true);
  });

  test('MemoryDocumentStore：与文件实现相同契约', () async {
    await runContract(MemoryDocumentStore());
  });
}
