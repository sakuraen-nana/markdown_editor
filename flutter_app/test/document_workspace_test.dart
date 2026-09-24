import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_editor/document/document_store.dart';
import 'package:markdown_editor/document/document_workspace.dart';
import 'package:markdown_editor/document/fixed_documents.dart';

void main() {
  late MemoryDocumentStore store;
  late DocumentWorkspaceController workspace;

  setUp(() {
    store = MemoryDocumentStore();
    workspace = DocumentWorkspaceController(store: store);
  });

  group('loadInitial：固定文档集与启动默认打开', () {
    test('首次启动创建全部固定文档并打开主文档', () async {
      await workspace.loadInitial();

      for (final document in kFixedDocuments) {
        expect(await store.read(document.fileName), document.template);
      }
      expect(workspace.currentFileName, 'welcome.md');
      expect(
        workspace.currentBlocks.first.text,
        contains('# Markdown 编辑器'),
        reason: '主文档模板载入编辑器',
      );
    });

    test('已存在内容不被模板覆盖', () async {
      await store.write('welcome.md', '# 用户自己的内容');
      await workspace.loadInitial();

      expect(await store.read('welcome.md'), '# 用户自己的内容');
      expect(workspace.currentBlocks.single.text, '# 用户自己的内容');
    });

    test('被删除的文档重新创建，其余文件不受影响', () async {
      await workspace.loadInitial();
      // 模拟外部删除 notes.md 后重启。
      final freshStore = MemoryDocumentStore();
      await freshStore.write('welcome.md', '# 用户自己的内容');
      await freshStore.write('todo.md', '- [ ] 保持');

      final fresh = DocumentWorkspaceController(store: freshStore);
      await fresh.loadInitial();

      expect(await freshStore.read('notes.md'), kNotesDocument.template);
      expect(await freshStore.read('welcome.md'), '# 用户自己的内容');
      expect(await freshStore.read('todo.md'), '- [ ] 保持');
    });
  });

  group('脏状态与保存', () {
    test('载入后不脏，修改后变脏，保存后写盘且不脏', () async {
      await workspace.loadInitial();
      expect(workspace.isDirty(), isFalse);

      final blocks = workspace.currentBlocks.toList();
      blocks[0] = blocks[0].copyWith(text: '# 改过的标题');
      workspace.updateBlocks(blocks);

      expect(workspace.isDirty(), isTrue);

      await workspace.save();
      expect(workspace.isDirty(), isFalse);
      expect(
        await store.read('welcome.md'),
        contains('# 改过的标题'),
      );
    });

    test('空改动不误报脏', () async {
      await workspace.loadInitial();
      workspace.updateBlocks(workspace.currentBlocks.toList());
      expect(workspace.isDirty(), isFalse);
    });
  });

  group('切换语义', () {
    test('selectDocument 切换内容，再切回保留内存修改', () async {
      await workspace.loadInitial();

      await workspace.selectDocument('notes.md');
      expect(workspace.currentFileName, 'notes.md');
      expect(workspace.currentBlocks.first.text, contains('# 笔记'));
      expect(workspace.isDirty(), isFalse, reason: '新打开的文档不脏');

      final blocks = workspace.currentBlocks.toList();
      blocks[0] = blocks[0].copyWith(text: '# 笔记（改）');
      workspace.updateBlocks(blocks);
      await workspace.selectDocument('todo.md');
      await workspace.selectDocument('notes.md');
      expect(workspace.currentBlocks.first.text, '# 笔记（改）');
      expect(workspace.isDirty(), isTrue, reason: '内存中的修改在切回后仍在');
    });

    test('discardUnsavedChanges 还原到已保存内容', () async {
      await workspace.loadInitial();
      final blocks = workspace.currentBlocks.toList();
      blocks[0] = blocks[0].copyWith(text: '# 即将放弃的修改');
      workspace.updateBlocks(blocks);
      expect(workspace.isDirty(), isTrue);

      workspace.discardUnsavedChanges();
      expect(workspace.isDirty(), isFalse);
      expect(
        workspace.currentBlocks.first.text,
        isNot(contains('即将放弃的修改')),
      );
      // 放弃后保存，落盘内容回到基线。
      await workspace.save();
      expect(await store.read('welcome.md'), kWelcomeDocument.template);
    });
  });
}
